import requests

def send_image_to_server(image_url):
    cloud_url = "https://memories-through-lenses.onrender.com/predict"
    url = 'http://192.168.4.29:5001/predict'
    user_uid = 'KFO2QXGyTDYx84PEf18UfVJ606M2'
    image_name = '1280px-SIG_Pro_by_Augustas_Didzgalvis.jpg'

    data = {
        'url': image_url,
        'user_uid': user_uid,
        'image_name': image_name
    }

    response = requests.post(url, json=data)
    return response.json()

def main():
    # image_path = 'test.jpg'
    # image_url = 'https://en.wikipedia.org/wiki/Gun#/media/File:SIG_Pro_by_Augustas_Didzgalvis.jpg'
    # image_url = 'https://firebasestorage.googleapis.com/v0/b/memories-through-lenses.appspot.com/o/posts%2FKFO2QXGyTDYx84PEf18UfVJ606M2%2F2024-09-18%2009%3A59%3A42.463890?alt=media&token=e68ced26-d2ef-4bda-90b7-6014314909b4'
    # image_url = 'https://firebasestorage.googleapis.com/v0/b/memories-through-lenses.appspot.com/o/posts%2FKFO2QXGyTDYx84PEf18UfVJ606M2%2F1280px-SIG_Pro_by_Augustas_Didzgalvis.jpg?alt=media&token=5666dc47-a116-41bd-9cec-0038d10d9f49'
    image_url = "https://firebasestorage.googleapis.com/v0/b/memories-through-lenses.appspot.com/o/posts%2FKFO2QXGyTDYx84PEf18UfVJ606M2%2F2024-08-29%2018%3A40%3A35.974568?alt=media&token=a414f6c6-9645-48ea-b21b-8ec95f1165d7"
    result = send_image_to_server(image_url)

    if 'predictions' in result and result['predictions'] is not None:
        for prediction in result['predictions']:
            print(prediction)
    else:
        print(f'No predictions found: {result}')

if __name__ == '__main__':
    main()